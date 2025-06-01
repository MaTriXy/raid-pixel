const broadcastSocket = require("./websocket_broadcast");
const player_active = []
let prev_state = {}

module.exports = (wss)=>{
    wss.on('connection', (ws) => {
        // Listen for messages from clients
        ws.on('message', async (message) => {
            let parsed_message = JSON.parse(message);
            let socket_name = parsed_message.Socket_Name;

            //Global Messages
            if(socket_name == "GlobalMessage"){
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
                    "player_type": parsed_message.player_type,
                    "isAttacking": parsed_message.isAttacking,
                    "isMoving": parsed_message.isMoving,
                    "Player_username": parsed_message.Player_username
                }

                broadcastSocket(wss, data_state)
                const index = player_active.findIndex(p => p.Player_GameID === parsed_message.Player_GameID);

                if (index === -1) {
                    player_active.push(data_state);
                } 
                else {
                    player_active[index] = data_state;
                }

                let populate_state = {
                    "Socket_Name": "populate_scene_" + ws.Spawn_Code,
                    "player_data": player_active
                }

                if(prev_state != populate_state){
                    ws.send(JSON.stringify(populate_state));

                    prev_state = populate_state;
                }
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

            //for player death
            else if(socket_name == "player_death"){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        Player_GameID: parsed_message.Player_GameID
                    }
                )
            }

            //for player health
            else if(socket_name == "player_health"){
                broadcastSocket(
                    wss,
                    {
                        Socket_Name: socket_name,
                        Player_GameID: parsed_message.Player_GameID,
                        Player_Health: parsed_message.Player_Health
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