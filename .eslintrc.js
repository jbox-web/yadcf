module.exports = {
  "parser": "eslint-plugin-coffee",
  "env": {
    "browser": true,
    "node": true
  },
  "plugins": [
    "coffee"
  ],
  "extends": [
    "plugin:coffee/eslint-recommended"
  ],
  "globals": {
    "define": true,
    "jQuery": true,
  },
  "rules": {
    "no-empty": [
      "warn"
    ],
    "no-prototype-builtins": [
      "warn"
    ],
    "coffee/no-unused-vars": [
      "warn"
    ],
    "no-unused-vars": [
      "warn",
      {
        "argsIgnorePattern": "^_"
      }
    ],
    "coffee/no-useless-escape": [
      "warn"
    ],
    "no-useless-escape": [
      "warn"
    ],
  }
}
