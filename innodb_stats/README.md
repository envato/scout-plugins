# InnoDB Stats Plugin

This plugin tracks the size of the buffer pool, usage and the read/write ratio.  It returns:

* buffer_pool_size: The currently configured buffer pool size.
* buffer_pool_capacity: The percentage of the configured buffer pool that's used.
* buffer_pool_pages_free: Number of free pages.
* page_size: The configured page size.
* write_percentage: The percentage of total queries that write data.