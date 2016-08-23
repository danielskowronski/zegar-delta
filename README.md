# zegar-delta

## modules
### minion
simple loop (menagable via systemd) that checks if alarm should be enabled; if so - starts buzzer and random pin reader; otherwise - displays clock and other info in second line (currently system IP but there will be a lot more read from files geneated by other modules)
### webgui
rack app for configuring some aspects of zegar delta; currently - alarms.json nice editor (JS powered)
### test-tools
varoius scripts for testing and debugging purposes (like buzzer killer)

## requirements
- ruby
- bundler

## local testing
use deploy.sh
