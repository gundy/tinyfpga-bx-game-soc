# TODO document the timer/counter driver

# Current thoughts

* simple clock divider that generates an interrupt on overflow
* makes two registers available:
  - a 32-bit accumulator
  - an increment value that gets added to the accumulator every clock cycle
* when the accumulator overflows, an overflow signal is set, which can be used to trigger an interrupt
