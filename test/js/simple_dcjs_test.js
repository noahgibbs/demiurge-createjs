const assert = require('assert');
//const createjs = require('createjs');
//var DCJS = require('./dcjs/dcjs.js');

describe('Simple DCJS', function() {
    describe('window.DCJS', function() {
        it('should define DCJS on window', function() {
            assert.notEqual(undefined, window.DCJS);
        });
    });
    describe('Set up DCJS', function() {
        it('should set up DCJS event handlers without error', function() {
            window.dcjs_game = new DCJS();

            var mock_ws = window.Mock.get_mock_websocket();
            dcjs_game.setTransport(new DCJS.WebsocketTransport(dcjs_game, mock_ws));
            var display = new DCJS.CreatejsDisplay(dcjs_game, { canvas: "displayCanvas" });
            dcjs_game.setMessageHandler("display", display);

            dcjs_game.setup();
            assert.equal(mock_ws, dcjs_game.getTransport().ws);
        });
    });
});
