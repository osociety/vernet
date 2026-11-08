/// Shared TCP port used by Wi-Fi/port-scan integration tests.
/// Kept out of [app_test.dart] so suite files can import without a circular
/// dependency.
int port = 0;

/// TCP port for an IPv6 server socket used by the IPv6 port-scan integration
/// test. Zero means the socket has not been bound yet.
int portIPv6 = 0;
