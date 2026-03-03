find ./ -type l -delete
rm -rf DerivedData
rm -rf Pods/*
bundle exec pod binary prebuild
bundle exec pod install
