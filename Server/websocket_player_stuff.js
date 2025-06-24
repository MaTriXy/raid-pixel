const broadcastSocket = require("./websocket_broadcast");
const player_active = []

module.exports = (wss)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //Global Messages
            if(socket_name == "SceneMessage_" + ws.Spawn_Code){
                broadcastSocket(
                    wss, 
                    {
                        "Socket_Name": socket_name,
                        "Receiver": parsed_message.Sender,
                        "GameID": parsed_message.GameID,
                        "Message": parsed_message.Message
                    }
                );
            }
           
            //for spawn players
            else if(socket_name === "Player_Spawn_" + ws.Spawn_Code){
                let data_state = {
                    "Socket_Name": socket_name,
                    "Player_inGameName": parsed_message.Player_inGameName,
                    "Player_GameID": parsed_message.Player_GameID,
                    "Player_posX": parsed_message.Player_posX,
                    "Player_posY": parsed_message.Player_posY,
                    "direction_value": parsed_message.direction_value,
                    "last_direction_value": parsed_message.last_direction_value,
                    "player_class": parsed_message.player_class,
                    "isAttacking": parsed_message.isAttacking,
                    "isMoving": parsed_message.isMoving,
                    "Player_username": parsed_message.Player_username,
                    "spawn_code": parsed_message.spawn_code,
                    "isDead": parsed_message.isDead,
                    "player_health": parsed_message.player_health
                }

                //send to everyone player
                broadcastSocket(wss, data_state)
                const index = player_active.findIndex(p => p.Player_GameID === parsed_message.Player_GameID);

                if (index === -1) {
                    player_active.push(data_state);
                } 
                else {
                    player_active[index] = data_state;
                }

                //send to self player
                let populate_state = {
                    "Socket_Name": "populate_scene_" + ws.Spawn_Code,
                    "player_data": player_active
                }
                ws.send(JSON.stringify(populate_state));
            }

            //for player loading progress in player interface
            else if(socket_name === "player_progress_interface"){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        Player_ID: parsed_message.Player_ID,
                        loading_value: parsed_message.loading_value
                    }
                )
            }

            //for playing leave lobby
            else if(socket_name === "leave_lobby"){
                let player_index = player_active.findIndex(key => key["Player_GameID"] == parsed_message.Player_GameID)

                if(player_index > -1){
                    player_active.splice(player_index, 1)
                }

                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        Player_GameID: parsed_message.Player_GameID
                    }
                )
            }
        });

        ws.on('error', (err) => {
            console.error(err);
        });

        ws.on('close', async () => {
            if(ws.GameID && ws.username){
                let player_index = player_active.findIndex(key => key["Player_GameID"] == ws.GameID)

                if(player_index > -1){
                    player_active.splice(player_index, 1)
                }
            }
        });
    });
}