function get_mock_cookie() {
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

