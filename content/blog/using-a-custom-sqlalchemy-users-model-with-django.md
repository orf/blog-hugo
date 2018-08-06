---
title: "Using a custom SQLAlchemy Users model with Django"
date: 2012-04-13 19:45:31.756918
---

I really dislike [Django's](https://www.djangoproject.com/) ORM. For my job I have written (and continue to maintain) a large internal project that uses Django's ORM, templating language and MVC framework to serve requests, and I made the unfortunate mistake of sticking with Django's ORM instead of using the much more powerful [SQLAlchemy](https://www.sqlalchemy.org/).

The one nice thing about Django's ORM is that it is easy, but that comes at the price of efficiency and power. For example the ability to add more than one record at a time to the database was only just added in Django 1.4, before that if you wanted to insert say 100 models Django would execute 100 INSERT queries, followed by a checkpoint if you were inside a transaction - the result being ~200 queries when 2 would have sufficed. This isn't to say that Django's ORM is bad, its just not right for me.

Anyway, I recently started a new project for my [company](https://www.vps-forge.com) which is based on Django. I wasn't going to make the same mistake twice so I used SQLAlchemy instead of Django's ORM, but I ran into a few problems - Django's ORM is tightly integrated into Django's users framework (Django ships with a default User class that can't be edited - you can expand it but that requires a one-to-one join on another table), and I needed a way to tie in my SQLAlchemy Users's model into Django's authentication system. Thankfully this was a lot easier than I thought, thank's to Django's modular design and easy to read codebase.

Django's User class has a few functions that we need to implement in our new User's class to be 100% compatible: is_authenticated, is_anonymous, check_password and set_password. For the password functions we can use Django's excellent make_password and check_password functions, and for the authentication functions we simply return True and False respectively. We also need to disconnect the update_last_login handler because it is incompatible with SQLAlchemy. You could re-write it if you wanted though.

So, lets jump right into it. Define yourself a Users class in your models.py (imports excluded for brevity)

```python
from django.contrib.auth.models import update_last_login, user_logged_in
user_logged_in.disconnect(update_last_login)

class User(Base):
    __tablename__ = "users"
    id       = Column(Integer, primary_key=True)
    username    = Column(String, unique=True)
    salt     = Column(String(10))
    password = Column(String(128))

    def is_authenticated(self):
        return True

    def is_anonymous(self):
        return False

    def check_password(self, raw_password):
        #TODO: Make this auto update using
        # check_passwords setter argument
        return check_password(raw_password, self.password)

    def set_password(self, password):
        if not self.salt:
            self.salt = random_characters(10)
        self.password = make_password(password,salt=self.salt)
```

Now create a new authentication backend and call it SQLAlchemyAuthenticationBackend.py:

```python
from sqlalchemy.orm.exc import NoResultFound
from Overseer import models

class SQLAlchemyUserBackend(object):
    supports_anonymous_user = True
    supports_inactive_user = True

    def __init__(self):
        self.session = models.Session()

    def authenticate(self, username=None, password=None):
        try:
            user = self.session.query(models.User).filter_by(username=username).one()
            if user.check_password(password):
                return user
        except NoResultFound:
            return None

    def get_user(self, user_id):
        try:
            user = self.session.query(models.User).filter_by(id=user_id).one()
        except NoResultFound:
            return None

        return user
```

And edit your settings.py to include this backend:

    AUTHENTICATION_BACKENDS =     ('path.to.SQLAlchemyAuthenticationBackend.SQLAlchemyUserBackend',)


And you are done. When you reference request.user it should now be your custom User class and not Django's. This also works nicely with the login decorators and even the default contrib.auth.login/logout views. It doesn't currently support user permissions simply because I don't need them, but they could be coded in fairly easily - or though they might be a bit to ingrained into Django's ORM to work with SQLAlchemy.

There might be some issues I haven't found with this, and if I do find any I will update this post, but for now it seems to be working fine. God, I love [Duck Typing](https://en.wikipedia.org/wiki/Duck_typing).
    