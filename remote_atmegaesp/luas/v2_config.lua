config = {}
config.led = 4

config.bt_right = 6
config.bt_left = 7
config.bt_forward = 5
config.bt_backward = 0
gpio.mode(config.bt_right,     gpio.INPUT, gpio.PULLUP)
gpio.mode(config.bt_left,      gpio.INPUT, gpio.PULLUP)
gpio.mode(config.bt_forward,   gpio.INPUT, gpio.PULLUP)
gpio.mode(config.bt_backward,  gpio.INPUT, gpio.PULLUP)

config.car_net_ip = "192.168.4.1"
config.car_net_port = 5000
config.broadcast_ip = "192.168.4.255"
config.steer_center = 87
config.current_steer = config.steer_center
config.steer_distance = -8 --the distance of the steering, negative for invert direction
config.current_direction = 1
config.default_speed = 1
config.current_speed = config.default_speed
config.current_relay = 15 -- gpio condition that drive relay

-- if data to be send was never changed, we will not send it repeatedly,
-- except if (timer_last_sending_limit) amount of time has passed
config.timer_last_sending = 0
config.timer_last_sending_limit = 500*1000 --maximum time passed before sending the same data again, in microsec
config.timer_last_speed_changed = 0

config.direction_adjust_right_delay_ms = 250 -- time to trigger adjust dir
config.direction_adjust_left_delay_ms = 260 -- duration of adjust dir
config.direction_adjust_right_steer = 87
config.direction_adjust_left_steer = 87

config.wifi_signal_log_interval = 500 -- milisecond interval for each signal strength display
  -- 0b 11111111 1111
  -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
  -- following 8 bits: steering pwm value
config.data = 0
config.data_mask = 15 -- will be masked for data, used when need to force certain relay to ON
config.last_data = 1295 -- (80<<4) | 0b1111
config.stop_checking_button = false
config.ssid = {}
return config
