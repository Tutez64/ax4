/**
 * Test case: namespace declaration with initializer.
 * The initializer should be parsed without breaking the file. Haxe has no namespaces: the
 * declaration is printed as a comment, which leaves a valid empty module.
 */
package {
    public namespace TestNamespaceDecl = "urn:test";
}
