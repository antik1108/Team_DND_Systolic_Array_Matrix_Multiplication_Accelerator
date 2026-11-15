# Presentation Script — Team DnD

Systolic Array Matrix Multiplication Accelerator · Project 12, Modern Computer Architecture

Total speaking time: about **16:05 min** for 17 slides, plus questions.

| Speaker | Slides |
|---|---|
| Syed Darain Qamar | 1–5 |
| Md Sajjan | 6 |
| Sibtain Ahmed Qureshi | 7–8 |
| Abuzar Haideri | 9–10 |
| Antik Mandal | 11–12 |
| Md Sajjan | 13 |
| Antik Mandal | 14–15 |
| Syed Darain Qamar | 16–17 |

## Slide 1: Systolic Array Matrix Multiplication Accelerator

**Syed Darain Qamar** · about 0:45 min

Good morning everyone. We are Team DnD, and our project is a Systolic Array Matrix Multiplication Accelerator, Project 12 of Modern Computer Architecture.

I am Syed Darain Qamar, and with me are Md Sajjan, Sibtain Ahmed Qureshi, Abuzar Haideri and Antik Mandal.

In simple words, we designed a small piece of hardware, written in Verilog, that multiplies matrices very fast. It uses a grid of 16 tiny calculators working at the same time.

The coloured grid on the right is a picture of that idea. The orange diagonal is a 'wave' of work moving through the grid. By the end of this talk you will know exactly what that wave is.

*On the slide:* Point at the 4 x 4 grid when you mention the 16 calculators.

## Slide 2: Matrix multiplication powers AI, but one-by-one is slow

**Syed Darain Qamar** · about 1:00 min

First, why does this matter? Almost all of AI comes down to matrix multiplication. Neural networks, image filters, even chatbots spend most of their time multiplying matrices.

Here we multiply A by B to get C. Each box of C is one row of A times one column of B, all added up.

For a small 4 by 4 matrix, that is 16 boxes, and each box needs 4 multiply-adds. So 64 operations.

If we have only one calculator doing them one after another, it takes 81 clock cycles. Our goal was to do many of these operations at the same time, and bring that number down.

*On the slide:* Point at 64, then at 81.

## Slide 3: The idea: a grid of tiny workers that pass numbers along

**Syed Darain Qamar** · about 1:00 min

Our solution is called a systolic array. Here are three easy ways to picture it.

One: like a heartbeat. The word 'systolic' comes from the heart. On every clock tick, data is pumped one step forward through the grid.

Two: like an assembly line. Each worker, which we call a processing element, does one small job, multiply and add, and then hands the numbers to its neighbour.

Three: read once, use often. Each number is read from memory only once, but four workers use it as it travels. That saves a lot of memory traffic.

This is the same idea Google uses in its TPU chip for AI. Theirs is 256 by 256. Ours is 4 by 4, so we can understand and test every part of it.

*On the slide:* Move left to right across the three cards.

## Slide 4: What we built: six Verilog modules, as the brief asked

**Syed Darain Qamar** · about 0:45 min

The project brief asked for six modules, and we built all six.

The MAC unit multiplies and adds. The processing element is one worker. The input buffers store matrices A and B. The controller runs the steps in order. The output registers hold the 16 answers. And the data interface lets a user load data, press start and read results.

We used signed 8-bit numbers, which is the same format real AI chips use, and 32-bit totals, so the answer can never overflow.

We also built a slow design with just one multiplier, so we can measure how much faster our array really is. And we made an FPGA board demo.

*On the slide:* Quickly touch each of the six cards.

## Slide 5: How the pieces connect

**Syed Darain Qamar** · about 1:00 min

Here is how the parts connect. Let us follow the data from left to right.

The host, on the far left, loads matrix A and matrix B into the two input buffers.

Next are the delay blocks, also called skew blocks. They hold some numbers back for a few ticks. We will see why on the next slides.

Then the numbers enter the 4 by 4 grid. A comes in from the left side, B comes in from the top.

When the work is finished, all 16 answers are copied into the output registers, and the host reads them out.

The controller at the bottom is the boss. It tells every block when to start, when to send data and when to stop.

Now Md Sajjan will explain what happens inside one worker.

*On the slide:* Trace the path with your hand: host, buffers, delay, grid, output.

## Slide 6: One processing element does just three things

**Md Sajjan** · about 1:00 min

Thank you. Each processing element is very simple. It does only three things.

Step one, receive: it takes a number of A from the left and a number of B from above.

Step two, multiply and add: it multiplies them and adds the result to its own running total. This total stays inside the same worker the whole time. That is why this design is called 'output-stationary'.

Step three, pass on: on the next clock tick it sends 'a' to its right neighbour and 'b' to the one below.

A small 'valid' signal travels along with the data. So a worker only adds when real numbers arrive, and never adds empty zeros by mistake.

Now Sibtain will explain the most important trick in the design.

*On the slide:* On the drawing: a from the left, b from the top, the total box, then the arrows going out.

## Slide 7: The trick: delay each row so the right numbers meet

**Sibtain Ahmed Qureshi** · about 1:15 min

Thank you. If all rows of A entered the grid at the same moment, the wrong numbers would meet each other, and the answers would be wrong.

So we delay them. Row 0 starts right away. Row 1 waits one tick. Row 2 waits two ticks. The dashed boxes in the picture are these waiting ticks.

Columns of B are delayed in the same way from the top.

Because of this staircase, the matching pair, a from row i and b from column j, always reaches worker i, j at the same tick. That time is k plus i plus j, and it is the same for A and B, so they always line up.

This staircase is the heart of every systolic array. It is also the diagonal 'wave' you saw on the first slide.

*On the slide:* Point at the dashed 'wait' boxes, then at the formula card.

## Slide 8: The controller runs six steps — 13 clock cycles in total

**Sibtain Ahmed Qureshi** · about 1:00 min

The controller is a state machine with six steps.

IDLE waits for the start button. CLEAR resets all totals to zero, which takes 1 cycle. FEED sends the 4 slices of A and B, so 4 cycles. DRAIN waits for the wave to reach the last worker, 7 cycles. CAPTURE copies all 16 answers out, 1 cycle. Then DONE says we are finished.

So 1 plus 4 plus 7 plus 1 equals 13 cycles. For any size N the formula is 3N plus 1.

We also proved that 7 drain cycles is the minimum. When we tried 6, the last worker was read one tick too early and our test failed.

Now Abuzar will show how we tested all of this.

*On the slide:* Walk along the six boxes, then point at '13 cycles'.

## Slide 9: We tested bottom-up: small parts first, then the chip

**Abuzar Haideri** · about 1:00 min

Thank you. We tested from the bottom up, exactly the workflow the brief asked for.

First the MAC unit alone, with 74 checks: positive and negative numbers, zero, the biggest values, and long sums.

Then one processing element, with 14 checks: does it pass data in exactly one tick, and does it add only valid data?

Then the whole 3 by 3 and 4 by 4 arrays, with 224 matrix products: identity matrices, zeros, negative numbers, fixed-point values and 100 random matrices.

Finally, a separate Python program using NumPy calculated every answer again on its own, as a second opinion.

In total we checked 2,800 answers and found zero mistakes. Every testbench checks itself and prints PASS or FAIL.

*On the slide:* Go down the staircase of checks, then point at 2,800 and 0.

## Slide 10: The waveform shows the diagonal wave of data

**Abuzar Haideri** · about 1:00 min

This is the waveform from our simulation. Time goes from left to right.

Look at the inputs in the middle. Each row of A starts one tick after the row above. That staircase proves the delay is working.

Now look at the totals near the bottom. The first worker grows 16, then 40, then 64, then 80. And 80 is the correct answer.

The last worker, at row 3, column 3, finishes at 386, and right after that the 'done' signal goes high, 13 cycles after start, exactly as our formula said.

Now Antik will show the results.

*On the slide:* Point at the staircase in the a_west rows, then the acc rows, then 'done'.

## Slide 11: 6× fewer cycles at 4×4 — and the gap grows with size

**Antik Mandal** · about 1:00 min

Thank you. This chart compares our systolic array, in green, with the one-multiplier design, in red. Lower bars are better.

At 4 by 4, the array needs 13 cycles and the simple design needs 81. That is 6.2 times faster.

The array's time grows slowly, in a straight line. The simple design's time grows like N cubed. So the bigger the matrix, the bigger our advantage.

At 8 by 8, it is 25 cycles against 577, which is 23 times faster.

All these numbers are measured in simulation, and they match our formulas exactly.

*On the slide:* Point at the 4x4 bars, then the 8x8 bars.

## Slide 12: On a real FPGA it is small, fast and 7.9× quicker

**Antik Mandal** · about 1:00 min

Next we turned the design into real FPGA hardware using synthesis tools.

It runs at up to 127 megahertz. It uses 16 hardware multipliers, one per worker, and only about 233 logic cells. That is very small, and it fits easily on a student board like the Basys-3.

Looking at the table: the one-multiplier design takes 874 nanoseconds for one matrix product. Our array takes 129 nanoseconds, and the pipelined version takes only 110.

That makes it 7.9 times faster in real time.

*On the slide:* Point at the four big numbers, then the highlighted 110 ns.

## Slide 13: Pipelining: one extra cycle, but every cycle is shorter

**Md Sajjan** · about 0:50 min

We also improved the speed with pipelining.

The slowest path in the chip was multiply and then add, both in a single clock cycle.

So we added one register in the middle. Now it takes 14 cycles instead of 13, but each cycle is shorter, because the clock can tick 26 percent faster.

The result: 13 cycles at 100 megahertz is 129 nanoseconds. 14 cycles at 127 megahertz is 110 nanoseconds. So it is 15 percent faster overall.

This is the same pipelining idea as the five-stage CPU pipeline we studied in class.

*On the slide:* Left card, arrow, right card.

## Slide 14: What limits it, and how we would improve it

**Antik Mandal** · about 1:00 min

We also want to be honest about the limits.

First, loading data is the bottleneck. Our simple interface loads only one number per cycle, so loading takes 32 cycles while computing takes only 13. Because of that, the overall speed-up is about 2 times. This is Amdahl's law. The fix is wide memory and DMA, like the TPU uses.

Second, each worker is busy only 4 of the 13 cycles, while the wave enters and leaves. The fix is to start the next job while the last one is still finishing.

Third, the size is fixed at 4 by 4. Bigger matrices must be cut into 4 by 4 tiles. The fix is a tiling controller and a larger array.

*On the slide:* Left side is the problem, right side is the fix.

## Slide 15: Live demo on the Basys-3 FPGA board

**Antik Mandal** · about 1:30 min

Now the live demo.

First, the board is programmed with our design. When I press the reset button, it loads two demo matrices, A and B.

When I press the centre button, the array computes C equals A times B in just 14 cycles.

Now I use the switches to pick a row and a column. Row 0, column 0 shows hex 0050, which is 80, the same as in our simulation. Row 3, column 3 shows hex 0182, which is 386.

The LEDs show that the job is done and how many cycles it took.

If the board is not available: we will show the simulation output and the waveform instead.

*On the slide:* Do it on the board: btnU, then btnC, then the switches.

## Slide 16: Who did what

**Syed Darain Qamar** · about 0:30 min

Very quickly, here is how we divided the work.

I led the team and worked on the architecture and integration. Md Sajjan built the MAC unit and processing element. Sibtain built the controller and the buffers. Abuzar handled testing and verification. Antik did the baseline design, the FPGA work, the demo and the performance analysis.

*On the slide:* Say each name while looking at that person.

## Slide 17: Thank you — questions?

**Syed Darain Qamar** · about 0:30 min

To sum up: we built 16 tiny workers with data pumped like a heartbeat. It takes exactly 3N plus 1, so 13, cycles, and simulation proved it. We checked 2,800 answers with zero mistakes. And on an FPGA it is 7.9 times faster than one multiplier.

Thank you for listening. We are happy to take your questions.

*On the slide:* Pause and invite questions.

## Likely questions

**Why output-stationary and not weight-stationary?**  
The total never moves, so we need no adders between workers and the controller stays simple. Only 8-bit numbers travel between workers.

**Why do you need the delay (skew)?**  
Without it, row i of A and column j of B would not meet at the same time. The delay makes both arrive at tick k + i + j.

**Why is drain exactly 2N − 1?**  
1 cycle for the buffer, N − 1 for the delay, and N − 1 to cross the grid. With 2N − 2 our test fails, so this is the minimum.

**Why does pipelining help if it adds a cycle?**  
It splits multiply and add, so the clock is 26% faster. 14 short cycles take less time than 13 long ones.

**Why is the end-to-end speed-up only about 2×?**  
Loading 32 numbers one per cycle takes longer than the 13-cycle compute. That is Amdahl's law. Real chips use wide memories.

**Why 8-bit fixed-point numbers?**  
Real AI chips like the TPU use 8-bit inputs with 32-bit totals. Each multiply fits in one FPGA DSP block, and nothing overflows.

**How do you know the results are correct?**  
Self-checking testbenches compare every answer with a Verilog reference model, and a separate NumPy program checked all 2,800 answers again.
