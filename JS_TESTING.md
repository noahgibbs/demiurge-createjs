# DCJS Javascript Testing

Javascript testing can be challenging in general.

For cross-browser testing, I started here:
https://philipwalton.com/articles/learning-how-to-set-up-automated-cross-browser-javascript-unit-testing/

## Browser Testing

Nearly everything DCJS uses Javascript for requires a browser. The
Javascript portion is essentially a display library based on CreateJS.

The current early, primitive test script bundles up the Javascript
tests using webpack. From there, they can be viewed in a browser to
run the tests, or cross-browser tested with tools like Sauce Labs.

Right now, start at the root of DCJS's source and run
test/bundle_and_test.sh and it should bundle up the JavaScript tests
and (if you're on a Mac) open Google Chrome to check the test.

While a local Mac-only browser command isn't terribly useful for
continuous integration, it should give you a good start if you want to
do that for your DCJS-based project.
