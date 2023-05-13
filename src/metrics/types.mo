module {
    public type Metric = {
        name: Text;
        t: Text; // Metric Type
        help: ?Text;
        value: Text;
        labels: [(Text, Text)];
    };

    public type Source = actor {
      metrics  : shared () -> async [Metric];
    };
}
