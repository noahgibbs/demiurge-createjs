const path = require('path');
const glob = require('glob');

module.exports = {
    context: __dirname + "/../..",
    target: "web",
    //externals: [ "createjs" ],
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
        modules: [
                  "node_modules",
                  "dcjs",
                  "vendor"
        ],
        extensions: [".web.coffee", ".web.js", ".coffee", ".js"],
        //alias: {
        //    "createjs": path.resolve(__dirname, "vendor/createjs.js"),
        //    "jquery": path.resolve(__dirname, "vendor/jquery.js")
        //},
        symlinks: true
    }
};
