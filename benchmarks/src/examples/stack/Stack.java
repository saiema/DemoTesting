package examples.stack;

import java.util.HashSet;
import java.util.Set;

public class Stack {

    private Node top;
    private int elements;

    public Stack() {
        top = null;
        elements = 0;
    }

    public void push(int elem) {
        Node newTop = new Node(elem);
        newTop.next(top);
        top = newTop;
        elements++;
    }

    public int peek() {
        if (isEmpty())
            throw new IllegalStateException("empty stack");
        return top.data();
    }

    public int pop() {
        if (isEmpty())
            throw new IllegalStateException("empty stack");
        int topData = top.data();
        top = top.next();
        elements--;
        return topData;
    }

    public boolean isEmpty() {
        return elements == 0;
    }

    public void clear() {
        top = null;
        elements = 0;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("TOP[");
        Node current = top;
        while (current != null) {
            sb.append(current.data());
            current = current.next();
            if (current != null)
                sb.append(", ");
        }
        sb.append("]BOTTOM");
        return sb.toString();
    }

    @Override
    public boolean equals(Object other) {
        if (other == null)
            return false;
        if (!(other instanceof Stack))
            return false;
        if (other == this)
            return true;
        Stack otherAsStack = (Stack) other;
        if (elements != otherAsStack.elements)
            return false;
        Node thisCurrent = top;
        Node otherCurrent = otherAsStack.top;
        while (thisCurrent != null && otherCurrent != null) {
            if (thisCurrent.data() != otherCurrent.data())
                return false;
            thisCurrent = thisCurrent.next();
            otherCurrent = otherCurrent.next();
        }
        return (thisCurrent == null) && (otherCurrent == null);
    }

    public boolean repOk() {
        return acyclic() && nodesAndElementsMatch();
    }

    private boolean acyclic() {
        Set<Node> visitedNodes = new HashSet<>();
        Node current = top;
        while (current != null) {
            if (!visitedNodes.add(current))
                return false;
            current = current.next();
        }
        return true;
    }

    private boolean nodesAndElementsMatch() {
        int countedNodes = 0;
        Node current = top;
        while (current != null) {
            countedNodes++;
            if (countedNodes > elements)
                return false;
            current = current.next();
        }
        return countedNodes == elements;
    }

}
