package fixture;

import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Edge cases for scripts/measure.sh: generics in signatures, multi-line signatures,
 * lambdas, an interface default method, a record, an inner class, and a text-free
 * annotation with arguments. Expected: 5 methods (apply, pick, run, describe, inner),
 * no false IFCHAIN or SWITCH, apply params=2.
 */
@SuppressWarnings({"unchecked", "{"})
public class Edge {

    record Pair(String left, String right) { }

    interface Formatter {
        String format(String in);
        default String describe() { return "fmt"; }
    }

    private final Map<String, List<Function<String, String>>> handlers = Map.of();

    public <T extends Comparable<T>> Map<String, List<T>> apply(Map<String, List<T>> in,
                                                                 Function<T, T> f)
            throws IllegalStateException {
        return in;
    }

    public String pick(String key) {
        Function<String, String> g = s -> {
            if (s.isEmpty()) {
                return "";
            }
            return s.trim();
        };
        return g.apply(key);
    }

    void run() {
        Runnable r = new Runnable() {
            @Override
            public void inner() { handlers.clear(); }
        };
        r.run();
    }
}
