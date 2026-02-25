## Rake Tasks for Building Gem

- rake build — Build x402payments-rails-0.1.0.gem into the pkg dir.
- rake build:checksum — Generate SHA512 checksum of the gem.
- rake clean — Remove any temporary products.
- rake clobber — Remove any generated files.
- rake install — Build and install the gem.
- rake install:local — Build and install the gem into ~/.gem.
- rake release[remote] — Create tag v0.1.0, build, and push the gem to the configured remote.

## CLI commands for running tests

- test — runs the test suite against the latest Rails version during development.
- test-all — runs the test suite across all supported Rails versions (7.2, 8.0, 8.1).

## Commands for running appraisals

- bundle exec appraisal install — generates/updates the appraisal Gemfiles under gemfiles/.
- bundle exec appraisal rails-7.2 rake test — run tests under the Rails 7.2 appraisal.
- bundle exec appraisal rails-8.0 rake test — run tests under the Rails 8.0 appraisal.
- bundle exec appraisal rails-8.1 rake test — run tests under the Rails 8.1 appraisal.
- bundle exec appraisal rake test — run the test suite across all appraisals.

## Checking code coverage

- Coverage is collected with `SimpleCov` from `test/test_helper.rb`.
- Run tests locally to generate coverage output: `bin/test` (or `bundle exec rake test`).
- Open the HTML report on macOS: `open coverage/index.html`.
- The CI matrix job uploads coverage as artifacts named `coverage-ruby<RUBY>-rails<RAILS>`.
- In GitHub Actions, open a workflow run and download the matching coverage artifact to inspect `coverage/index.html`.
