## Contributing

MetalPetal 1.x is in maintenance mode. Contributions should address severe security defects, data-corruption defects, or regressions within the existing compatibility contract.

New feature development belongs to Raster 2.x, which begins after the MetalPetal 1.26.0 tag.

Report suspected security vulnerabilities privately according to [SECURITY.md](SECURITY.md); do not disclose them in a public issue.

### Pull Requests

If you know exactly how to fix an in-scope defect, open a pull request instead of an issue. Pull requests are easier than patches or inline code blocks for discussing and merging changes.

If you can't make the change yourself, please open an issue after making sure
that one isn't already logged.

### Contributing Code

Fork this repository, make your change (preferably in a branch named for the
topic), send a pull request.

- Pull requests should contain small, incremental change.

- Code must compile without warnings or static analyzer warnings.

- The committer is responsible for addressing any problems found in the future that the change may cause.

- Follow the `API Design Guidelines`

- Run the local verification commands appropriate to your change before sending a pull request:

```bash
swift build
swift test
bash test.sh
bash Scripts/test-integration.sh
```

### API Design Guidelines

#### Objective-C

Basically, you should follow Apple's [Objective-C Conventions](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/Conventions/Conventions.html) as well as [Coding Guidelines for Cocoa](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html).

Additionally:

- Use `NS_ENUM` or `NS_OPTIONS` for enumerations. 

- All interfaces should be marked with nullability annotations.

- Always review the generated Swift interfaces, make sure that every single API conforms to the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).  Use `NS_SWIFT_NAME` / `NS_SWIFT_UNAVAILABLE` / `NS_REFINED_FOR_SWIFT` whenever needed.

#### Swift

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
