const broadcastSocket = require("./websocket_broadcast");

module.exports = (wss)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //for player loading progress in player interface
            if(socket_name === "player_progress_interface"){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        Player_ID: parsed_message.Player_ID,
                        loading_value: parsed_message.loading_value
                    }
                )
            }
        });

        ws.on('error', (err) => {
            console.error(err);
        });
    });
}