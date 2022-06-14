package examples.stack;

public class Node {

    private int data;
    private Node next;

    public Node(int data) {
        this.data = data;
    }

    public int data() {
        return data;
    }

    public void data(int data) {
        this.data = data;
    }

    public Node next() {
        return next;
    }

    public void next(Node next) {
        this.next = next;
    }

}
