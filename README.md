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

rspec-shiori is default disabled

enable all test case skip
```bash
$ SHIORI=true rspec spec/
$ SHIORI=1 rspec spec/
```

disable a test case skip
```
it "test", shiori: false do
  # do something
end
```

cache directory is tmp/cache/shiori

## License

Apache License Version 2.0
