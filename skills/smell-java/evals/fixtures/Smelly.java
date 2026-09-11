package fixture;

import java.util.*;
import java.util.stream.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

/** Fixture for scripts/measure.sh: every smell here is on purpose. */
public class Smelly implements OrderConstants {

    public static final int STATUS_NEW = 1;
    public static final int STATUS_PAID = 2;
    public static final int STATUS_SHIPPED = 3;

    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;
    private final Notifier notifier;
    private final Clock clock;
    private final AuditLog auditLog;
    private final PriceCalculator priceCalculator;

    @Autowired
    private MetricsClient metrics;

    private Optional<String> cachedName;

    public Smelly(OrderRepository orderRepository, PaymentGateway paymentGateway, Notifier notifier,
                  Clock clock, AuditLog auditLog, PriceCalculator priceCalculator) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
        this.notifier = notifier;
        this.clock = clock;
        this.auditLog = auditLog;
        this.priceCalculator = priceCalculator;
    }

    // a "{" inside a string and a comment: { must not count
    public String label(Order order, boolean verbose, boolean html, String prefix, int width) {
        String s = "{" + prefix; // {
        char c = '{';
        return switch (order.getKind()) {
            case STANDARD -> "std" + s + c;
            case EXPRESS -> "exp";
            case GIFT -> "gift";
            case BULK -> "bulk";
        };
    }

    public double discount(Order order) {
        if (order.getKind() == Kind.STANDARD) {
            return 0;
        } else if (order.getKind() == Kind.EXPRESS) {
            return 0.05;
        } else if (order.getKind() == Kind.GIFT) {
            return 0.1;
        } else {
            return 0.2;
        }
    }

    public void process(Order order, Customer customer) {
        if (order != null) {
            if (customer != null) {
                if (customer.getAddress() != null) {
                    for (Item item : order.getItems()) {
                        if (item.getPrice() > 0) {
                            if (item.getStock() == null) {
                                auditLog.warn(item);
                            }
                        }
                    }
                }
            }
        }
        String city = customer.getAddress().getCity().getName();
        Object o = order.getPayload();
        if (o instanceof String) {
            notifier.send((String) o);
        } else if (o instanceof Integer) {
            notifier.send(String.valueOf(o));
        }
        List<String> names = order.getItems().stream().map(Item::getName).collect(Collectors.toList());
        String msg = String.format("%s %s", city, names);
        for (int i = 0; i < names.size(); i++) {
            auditLog.info(names.get(i));
        }
        Date now = new Date();
    }

    @Transactional
    private void persist(Order order) {
        orderRepository.save(order);
    }

    public OrderDto toDto(Order order) {
        OrderDto dto = new OrderDto();
        dto.setId(order.getId());
        dto.setKind(order.getKind());
        dto.setTotal(order.getTotal());
        dto.setCurrency(order.getCurrency());
        dto.setCustomerName(order.getCustomer().getName());
        dto.setCity(order.getCustomer().getAddress().getCity().getName());
        dto.setCreated(order.getCreated());
        dto.setNotes(order.getNotes());
        return dto;
    }

    public Optional<Order> find(long id) {
        try {
            return orderRepository.findById(id);
        } catch (RuntimeException e) {
            return Optional.empty();
        }
    }

    public void ship(Order order) {
        switch (order.getStatus()) {
            case STATUS_NEW:
                throw new IllegalStateException();
            case STATUS_PAID:
                paymentGateway.capture(order);
                break;
            case STATUS_SHIPPED:
                break;
            default:
                break;
        }
    }
}
