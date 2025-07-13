# Rspec::Shiori

When you run rspec, it will cache the code and skip the test run the next time the code is the same.

## Installation

```
gem "rspec-shiori", git: 'https://github.com/longicorn/rspec-shiori.git', branch: 'master'
```

```bash
bundle install
```

## Usage

disable a test case skip
```
it "test", shiori: false do
  # do something
end
```

disable all test case skip
```bash
$ SHIORI=false rspec spec/
```

cache directory is tmp/cache/shiori

## License

Apache License Version 2.0
