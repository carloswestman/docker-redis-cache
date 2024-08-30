
# Visual Representation of the Redis LRU Eviction Algorithm

The ideal eviction algorithm should consistently remove the oldest records to optimize cache management. This visual representation demonstrates how the Redis LRU (Least Recently Used) algorithm effectively evicts older records, balancing precision with performance.

For more detailed information, refer to the [Redis LRU eviction algorithm documentation](https://redis.io/topics/lru-cache).

### Initial Redis Cache State
Figure 1 illustrates the initial state of the Redis cache. The newest data is positioned in the top left corner, with data aging progressively as you move to the right and downward. A perfect eviction algorithm would remove the oldest data from the bottom right, moving leftward and upward.

![Redis initial collection state, original data in green](./assets/redismap_after_write.png)

**Figure 1:** Initial Redis cache state with original data in green.

### Redis LRU Eviction Process
Figure 2 shows the state of the Redis cache after the LRU algorithm has evicted older records. The evicted data is highlighted in red, demonstrating how the algorithm prioritizes the removal of less recently used entries.

![Redis LRU eviction algorithm discarding older samples, evicted data in red](./assets/redismap_after_read.png)

**Figure 2:** Redis cache state after LRU eviction, with evicted data in red.
