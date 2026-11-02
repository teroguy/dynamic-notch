.PHONY: all build install run clean

all: install

build:
	@DEVELOPER_DIR=$$(test -d /Applications/Xcode.app/Contents/Developer && echo /Applications/Xcode.app/Contents/Developer || xcode-select -p) \
	xcodebuild -scheme boringNotch -configuration Debug -derivedDataPath .build build -quiet

install:
	@./install.sh

run:
	@open "/Applications/Boring Notch.app"

clean:
	@rm -rf .build
