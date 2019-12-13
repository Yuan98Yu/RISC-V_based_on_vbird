## 0. 如何接入新外设？

1. 使用 GPIO 

2. 新的地址

## 1. 外设如何接入 GPIO ？

- GPIO 何处 实例化？

  `e203_soc_top`->`e203_subsys_top`->`e203_subsys_main`->`e203_subsys_perips.v`->`sirv_gpio_top`->`sirv_gpio.v`

- 这些外设的信号如何接入 GPIO ？

  - （√）直接在 .xdc 映射外设的引脚与 GPIO 的信号线，对外设操作通过操作 GPIO 的对应接口实现
  - （×）可以如 PWM， QSPI、UART一样，先构建一个 SoC 内部的模块，再复用 GPIO 的 IOF 功能

- 软件如何配置 每个 I/O 输入或输出？

  - 模块 `sirv_gpio_top` （在`e203_subsys_perips.v` 中实例化）的输出有表明每个 GPIO 端口的读、写是否有效，用于顶层模块判断输入输出值是否有效，如下：

    ```verilog
        .io_port_pins_0_o_oe             (io_pads_gpio_0_o_oe),
        .io_port_pins_0_o_ie             (io_pads_gpio_0_o_ie),
    ```

    所有顶层的模块（`e203_soc_top`->`e203_subsys_top`->`e203_subsys_main`）都保留了上述的几个输出信号。

  - *由上述可知，有其它机制配置 I/O，暂未找到

  - 每个 I/O 端口都可配置为 IOF，配置为 IOF 后也可以配置其为输入或输出，详见下

- 如何配置 每个 I/O 为 IOF？

  - 硬件写死

  - `e203_subsys_perips.v` 中，993行开始，通过assign语句配置每个 I/O 的 IOF1/IOF2 是否使用，如 

  ```verilog
    assign gpio_iof_0_0_o_valid      = 1'b0;
  ```

- 在被配置为 IOF 后，软件如何配置 每个 I/O 使用 IOF0 或 IOF1？

  同上一问题，`e203_subsys_perips.v` 中，993行开始，通过assign语句配置每个 IOF （IOF0 和 IOF1）是否使用的同时，配置其是输入或输出，若是输出，则指定输出值，如 

  ```verilog
    assign spi_pins_0_io_pins_cs_0_i_ival = gpio_iof_0_2_i_ival;
    assign gpio_iof_0_2_o_oval       = spi_pins_0_io_pins_cs_0_o_oval;
    assign gpio_iof_0_2_o_oe         = spi_pins_0_io_pins_cs_0_o_oe;
    assign gpio_iof_0_2_o_ie         = spi_pins_0_io_pins_cs_0_o_ie;
  ```

  软件可通过改变类似 `spi_pins_0_io_pins_cs_0_o_oe` 信号的值

