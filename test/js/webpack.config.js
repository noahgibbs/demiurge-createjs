const path = require('path');
const glob = require('glob');

module.exports = {
    entry: glob.sync("./test/js/*test.js"),
    output: {
        filename: "test/js/test_bundle.js"
    },
    module: {
        loaders: [
          { test: /\.coffee$/, loader: "coffee-loader" }
        ]
    },
    resolve: {
        extensions: [".web.coffee", ".web.js", ".coffee", ".js"]
    }
};
