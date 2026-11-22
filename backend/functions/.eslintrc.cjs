module.exports = {
  root: true,
  env: {node: true, es2022: true},
  extends: ['eslint:recommended'],
  ignorePatterns: ['lib/'],
  overrides: [{
    files: ['*.ts'],
    parser: '@typescript-eslint/parser',
    // TypeScript resolves types and enforces noUnusedLocals.
    rules: {'no-undef': 'off', 'no-unused-vars': 'off'},
  }],
};
