// Broadcast message to all clients
function broadcastSocket(wss, data){
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            if(data.Socket_Name === "damage_core_update"){
                console.log(data)
            }
            client.send(JSON.stringify(data));
        }
    });
}

module.exports = broadcastSocket;