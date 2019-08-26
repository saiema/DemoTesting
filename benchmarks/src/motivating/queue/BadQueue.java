package motivating.queue;

import motivating.queue.QueueNode;

public class BadQueue {
	
	private QueueNode front;
	private QueueNode last;
	private int size = 0;
	
	public BadQueue() {}
	
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

}
