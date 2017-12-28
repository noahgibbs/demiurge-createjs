#!/bin/bash

./node_modules/webpack/bin/webpack.js test/js_page_test.js test/js_page_test_bundle.js
open -a "Google Chrome.app" test/js_page_test.html
