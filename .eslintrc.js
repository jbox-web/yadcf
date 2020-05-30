module.exports = {
  "env": {
    "browser": true,
    "node": true
  },
  "plugins": [
    "coffeescript"
  ],
  "extends": [
    "eslint:recommended"
  ],
  "globals": {
    "define": true,
    "jQuery": true,
  },
  "rules": {
    "no-unused-vars": [
      "warn",
      {
        "argsIgnorePattern": "^_"
      }
    ],
    "no-prototype-builtins": [
      "warn"
    ],
    "no-useless-escape": [
      "warn"
    ],
  }
}
