module.exports = {
  root: true,
  env: {
    es2022: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 'latest',
  },
  ignorePatterns: ['node_modules/', 'package-lock.json'],
  overrides: [
    {
      files: ['renderer/**/*.js'],
      env: {
        browser: true,
        node: false,
      },
    },
  ],
};
