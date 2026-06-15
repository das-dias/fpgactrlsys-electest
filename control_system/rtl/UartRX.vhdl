library IEEE;
	use ieee.std_logic_1164.ALL;
	use ieee.std_logic_arith.ALL;
	use ieee.std_logic_signed.ALL;

entity UartRX is
	generic(
		clockFreq			: integer 	:= 96_000_000;
		baudRate				: integer 	:= 115200
	);
	Port(
		clk					: in std_logic;
		rst	 				: in std_logic;

		dataOut 				: out std_logic_vector(7 downto 0);
		outputRdy			: out std_logic;

		uartRXIn				: in std_logic
	);
end entity;

architecture Behavioral of UartRX is

	-- constants
	constant baudRatePeriod						: std_logic_vector(24 - 1 downto 0)		:= conv_std_logic_vector((clockFreq / baudRate),24);
	constant baudRateHalfPeriod				: std_logic_vector(24 - 1 downto 0)		:= conv_std_logic_vector((clockFreq / (baudRate * 2)),24);

	type uartRxStateType is
	(
		idle,satrtHalfPeriodRx_st,checkStartBit_st,waitForReceiveData_st,uartReceiveData_st,waitForStopBit_st,checkStopBit_st
	);

	-- variable
	signal uartRxState						: uartRxStateType := idle;
	signal uartRx_r1							: std_logic;
	signal uartRx_r2							: std_logic;
	signal cntrPeriodUartRx					: std_logic_vector(24 - 1 downto 0);
	signal bitCntrUartRx						: std_logic_vector(3 - 1 downto 0);
	signal uartReceiveData					: std_logic_vector(8 - 1 downto 0);
	signal framErrorRx						: std_logic;
	
	signal dataOut_x							: std_logic_vector(8 - 1 downto 0);
	signal outputRdy_x						: std_logic;

begin

	process(clk)
	begin
		if rising_edge(clk) then
			uartRx_r1			<= uartRXIn;
			uartRx_r2			<= uartRx_r1;

			outputRdy			<= outputRdy_x;
			if outputRdy_x = '1' then
			 dataOut				<= dataOut_x;
			end if;

		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then

			cntrPeriodUartRx			<= cntrPeriodUartRx + 1;
			outputRdy_x					<= '0';
			framErrorRx					<= '0';

			case(uartRxState) is
				when idle =>
					cntrPeriodUartRx			<= (others => '0');
					bitCntrUartRx				<= (others => '0');

					if uartRx_r2 = '1' and uartRx_r1 = '0' then
						uartRxState					<= satrtHalfPeriodRx_st;
					end if;

				when satrtHalfPeriodRx_st =>
					if '0' & cntrPeriodUartRx = baudRateHalfPeriod - 2 then
						uartRxState					<= checkStartBit_st;
					end if;

				when checkStartBit_st =>
					cntrPeriodUartRx			<= (others => '0');
					if uartRx_r1 = '0' then
						uartRxState					<= waitForReceiveData_st;
					else
						framErrorRx					<= '1';
						uartRxState					<= idle;
					end if;

				when waitForReceiveData_st =>
					if '0' & cntrPeriodUartRx = baudRatePeriod - 2 then
						uartRxState					<= uartReceiveData_st;
					end if;

				when uartReceiveData_st =>
					cntrPeriodUartRx			<= (others => '0');
					bitCntrUartRx				<= bitCntrUartRx + 1;
					uartReceiveData			<= uartRx_r2 & uartReceiveData(7 downto 1);
					
					if '0' & bitCntrUartRx = 7 then
						uartRxState					<= waitForStopBit_st;
					else
						uartRxState					<= waitForReceiveData_st;
					end if;

				when waitForStopBit_st =>
					dataOut_x						<= uartReceiveData;
					if '0' & cntrPeriodUartRx = baudRatePeriod - 2 then
						uartRxState					<= checkStopBit_st;
					end if;

				when checkStopBit_st =>
					cntrPeriodUartRx			<= (others => '0');
					if uartRx_r1 = '1' then
						uartRxState					<= idle;
						outputRdy_x					<= '1';
					else
						framErrorRx					<= '1';
						uartRxState					<= idle;
					end if;

				when others =>
					uartRxState					<= idle;

			end case;

			if rst = '1' then
				uartRxState					<= idle;
			end if;

		end if;
	end process;

end architecture;
