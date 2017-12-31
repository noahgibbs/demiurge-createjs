const path = require('path');
const glob = require('glob');

module.exports = {
    context: __dirname + "/../..",
    target: "web",
    //externals: [ "createjs" ],
    entry: glob.sync("./test/js/*test.js").
    concat([
            // Include vendor scripts, as the browser bundle will
            "./vendor/createjs.js",
            "./vendor/jquery.js",
            "./vendor/bcrypt.min.js",
            "./vendor/reconnecting-websocket.min.js",
            "./vendor/sha1.min.js",

            // Include test helpers
            "./test/jshelper/cookie_mock.js",

            // Include modular, un-minified DCJS to test latest changes
            "./dcjs/dcjs.coffee",
            "./dcjs/dcjs_websocket.coffee",
            "./dcjs/dcjs_createjs.coffee",
            "./dcjs/dcjs_createjs_loader.coffee",
            "./dcjs/dcjs_createjs_spritesheet.coffee",
            "./dcjs/dcjs_createjs_spritestack.coffee",
            "./dcjs/dcjs_createjs_text_anim.coffee"
            ]),
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
