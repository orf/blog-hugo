
const prodPlugins = {
    '@fullhuman/postcss-purgecss': {
        content: ['public/**/*.html'],
        whitelist: [
            'highlight',
            'language-bash',
            'pre',
            'video',
            'code',
            'content',
            'h3',
            'h4',
            'ul',
            'li'
        ]
    },
    autoprefixer: {},
    cssnano: {preset: 'default'}
}

module.exports = {
    plugins: process.env.HUGO_ENVIRONMENT === "production" ? prodPlugins : {}
};
