if(window.Mock === undefined) {
  window.Mock = {
  };
};

window.Mock.get_mock_cookie = function () {
    var mock = {
        value_: '', 

        get cookie() {
            return this.value_;
        },

        set cookie(value) {
            this.value_ += value + ';';
        }
    };
    return mock;
};

