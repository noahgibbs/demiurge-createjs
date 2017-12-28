const assert = require('assert');
//const createjs = require('createjs');
//var DCJS = require('./dcjs/dcjs.js');

describe('Simple DCJS', function() {
        describe('window.DCJS', function() {
                it('should define DCJS on window', function() {
                        assert.notEqual(undefined, window.DCJS);
                    });
            });
    });
