const { createRunOncePlugin } = require('@expo/config-plugins');

const withCityPopProcessor = (config) => {
    return config;
};

module.exports = createRunOncePlugin(
    withCityPopProcessor,
    'city-pop-processor',
    '1.0.0'
);
