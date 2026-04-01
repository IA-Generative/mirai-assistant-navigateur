module.exports = {
  testEnvironment: 'jsdom',
  setupFiles: ['./tests/setup.js'],
  testMatch: ['**/tests/**/*.test.js'],
  collectCoverageFrom: [
    'src/dm/bootstrap.js',
    'src/dm/telemetry.js',
    'src/background.js',
    'src/recording.js',
    'src/compat.js'
  ]
};
