const express = require("express");
const route = express.Router();

module.exports = function(pool){
    route.get("/getPlayerCount", async (req, res)=>{
        try{
            const query = await pool.query("SELECT * FROM game_data")
    
            let status = "Failed";
            let count = 0
    
            if(query.rows.length > 0){
                let data = query.rows[0]
                status = "Success";
                count = data.player_count;
            }
    
            res.status(200).json({ status: status, count: count })
        }
        catch(err){
            console.log(err)
        }
    });

    return route
};