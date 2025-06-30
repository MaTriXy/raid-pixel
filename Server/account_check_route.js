const express = require("express")
const route = express.Router();

const cloudinary = require("cloudinary").v2;

require("dotenv").config({ path: require("path").resolve(__dirname, "../keys.env")})

cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

async function delete_image(profile_hash){
    try{
        if(profile_hash && profile_hash != "default_profile_vw2q2o"){
            cloudinary.uploader.destroy(profile_hash, function(result) { console.log(result) });
        }
    }
    catch(err){
        console.log(err);
    }
}

module.exports = function(pool){
    route.post("/check_account", async (req, res)=>{
        try{
            let username = req.body.username;

            const query = await pool.query('SELECT * FROM account WHERE username = $1', [username]);
    
            if(query.rows.length === 0){
                console.log("Account does not exist");
                return;
            }
    
            if(query.rows[0].account_type == "Guest"){
                const find_player = await pool.query('SELECT * FROM player_infos WHERE username = $1', [username]);
    
                if(find_player.rows.length > 0){
                    const image_name = find_player.rows[0].profile_hash;
    
                    if(image_name){
                        await delete_image(image_name);
                    }
                }
    
                await pool.query('DELETE FROM account WHERE username = $1', [username]);
                await pool.query('DELETE FROM player_infos WHERE username = $1', [username]);
            }
            else{
                await pool.query('UPDATE account SET isonline = $1 WHERE username = $2', [false, username]);
            }

            res.status(200).json({ status: "Success" })
        }
        catch(err){
            console.log(err);
        }
    })

    return route
}