find ./ -type l -delete
rm -rf DerivedData
rm -rf Pods/*
bundle exec pod binary fetch
bundle exec pod install
