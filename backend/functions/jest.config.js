module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.ts'],
  moduleNameMapper: {
    '^firebase-functions$': '<rootDir>/test/__mocks__/firebase-functions.ts',
    '^firebase-functions/(.*)$': '<rootDir>/test/__mocks__/firebase-functions.ts',
    '^firebase-admin$': '<rootDir>/test/__mocks__/firebase-admin.ts',
    '^@google-cloud/monitoring$': '<rootDir>/test/__mocks__/google-cloud__monitoring.ts',
    '^\.\./services\/payments\/stripeService$': '<rootDir>/test/__mocks__/stripeService.ts'
  },
  setupFiles: ['<rootDir>/test/jest.setup.js'],
  globals: {
    'ts-jest': {
      tsconfig: 'tsconfig.test.json',
    },
  },
}; 