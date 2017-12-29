const path = require('path');
const glob = require('glob');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');

module.exports = {
    context: __dirname,
    target: "web",
    entry: glob.sync("*.coffee")
    .concat([
             "../vendor/createjs.js",
             "../vendor/jquery.js",
             "../vendor/bcrypt.min.js",
             "../vendor/reconnecting-websocket.js",
             "../vendor/sha1.min.js"
             ]),
    output: {
        filename: "dcjs/dcjs-combined.min.js"
    },
    module: {
        loaders: [
          { test: /\.coffee$/, loader: "coffee-loader" }
        ]
    },
    resolve: {
        extensions: [".web.coffee", ".web.js", ".coffee", ".js"],
        //alias: {
        //    "createjs": path.resolve(__dirname, "vendor/createjs.js"),
        //    "jquery": path.resolve(__dirname, "vendor/jquery.js")
        //},
        symlinks: true
    },
    plugins: [
              new UglifyJsPlugin()
    ]
};
