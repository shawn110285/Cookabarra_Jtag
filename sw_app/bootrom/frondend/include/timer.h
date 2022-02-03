
#ifndef __TIMER_H__
#define __TIMER_H__

#include <stdint.h>

typedef void (*callback)(void);


uint64_t get_cycle_value();
uint64_t timer_read(void);
void timecmp_update(uint64_t new_time);
void timer_enable(uint64_t time_base, callback timer_cb);
void timer_disable(void);
void simple_timer_handler(void);
#endif  // __TIMER_H__
