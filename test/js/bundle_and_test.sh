#!/bin/bash

./node_modules/.bin/webpack --config test/js/webpack.config.js && open -a "Google Chrome.app" test/js/mocha_tests.html
