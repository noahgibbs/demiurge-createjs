if(window.Mock === undefined) {
  window.Mock = {
  };
};

window.Mock.get_mock_websocket = function() {
    var mock = {
        _ready: true,
        _onopen: undefined,
        _onclose: undefined,
        _onmessage: undefined,
        _sent_data: [],

        get readyState() {
            return this._ready;
        },

        // onmessage_handler(evt)
        // evt.data - JSON data for the message
        set onmessage(value) {
            this._onmessage = value;
        },

        // onopen_handler()
        set onopen(value) {
            this._onopen = value;
        },

        // onclose_handler()
        set onclose(value) {
            this._onclose = value;
        },

        send: function (data) {
            _sent_data.concat([data]);
        },

        get_sent: function() { return this._sent_data; },

        receive: function(received_data) {
            if(this._onmessage != undefined) {
                this._onmessage({data: received_data});
            };
        },

        open: function() {
            if(this._onopen != undefined) {
                this._onopen();
            };
        },

        close: function() {
            if(this._onclose != undefined) {
                this._onclose();
            };
        }
    };
    return mock;
};

