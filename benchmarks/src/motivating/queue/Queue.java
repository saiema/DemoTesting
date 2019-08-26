package motivating.queue;

import java.util.HashSet;
import java.util.Set;

import motivating.queue.QueueNode;
import randoop.CheckRep;

public class Queue {
	
	private QueueNode front;
	private QueueNode last;
	private int size = 0;
	
	public Queue() {}
	
	public void enqueue(int elem) {
		QueueNode newNode = new QueueNode(elem);
		if (front == null) {
			front = newNode;
			last = newNode;
		} else {
			last.next = newNode;
			last = newNode;
		}
		size++;
	}
	
	public int peek() {
		if (isEmpty()) throw new IllegalStateException("peek on empty queue");
		return front.value;
	}
	
	public void dequeue() {
		if (isEmpty()) throw new IllegalStateException("dequeue on empty queue");
		front = front.next;
		size--;
	}
	
	public boolean isEmpty() {
		return size() == 0;
	}
	
	public int size() {
		return size;
	}
	
	@Override
	public String toString() {
		StringBuilder sb = new StringBuilder("");
		sb.append('O').append('[');
		for (QueueNode current = front; current != null; current = current.next) {
			sb.append(current.value);
			if (current.next != null) {
				sb.append(", ");
			}
		}
		sb.append(']').append('I');
		return sb.toString();
	}
	
	@CheckRep
	public boolean repOk() {
		return aciclycAndCorrectSize() && fromFrontToLast();
	}
	
	private boolean aciclycAndCorrectSize() {
		Set<QueueNode> visited = new HashSet<QueueNode>();
		for (QueueNode current = front; current != null; current = current.next) {
			if (visited.contains(current)) return false;
			visited.add(current);
		}
		return visited.size() == size();
	}
	
	private boolean fromFrontToLast() {
		QueueNode current;
		if (front == null) return true;
		for (current = front; current.next != null; current = current.next) {}
		return current == last;
	}

}
