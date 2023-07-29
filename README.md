# ExistentialAnnotator
## Motivation

As [Swift 6](https://forums.swift.org/t/on-the-road-to-swift-6/32862) release approaches it is going to become imperative that we all mark [existential types](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md) with `any`. Xcode does offer solution in form of fixit but that is still not enough for large codebases. Failing to explicitly mark existential types will result in compilation error once Swift 6 is out.

## How does Swift existentialannotator work?

This is a command line tool written in Swift that utilizes [Apple's Swift Syntax library]https://github.com/apple/swift-syntax() to find all protocol declarations. Then it rewrites all
 existential types such that keyword `any` is added before type annotation. It also relies on [Argument parser](https://github.com/apple/swift-argument-parser) to provide common command line functionality in addition to parsing the single argument that this tool takes.

## Usage

1. In Terminal `cd`  in to your project directory where you want to perform the annotation.
2. Run `existentialannotator .` and let it do its magic.

## Contributing

While existentialannotator does what it is supposed to, this is just a project that I hacked together to help myself. If you find something that needs improvement, feel free to open a pull request and I will do my best to respond in a timely manor.
