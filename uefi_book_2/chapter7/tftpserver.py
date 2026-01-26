from tftpy import TftpServer


server = TftpServer('./')
server.listen('0.0.0.0', 6969)
