const path = require('path');
const glob = require('glob');

module.exports = {
    entry: glob.sync("./test/js/*test.js"),
    output: {
        filename: "test/js/js_page_test_bundle.js"
    }
};
