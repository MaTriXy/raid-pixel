const express = require("express");
const route = express.Router();
const sanitize = require("sanitize-html");
const bcrypt = require("bcryptjs")
const { v4: uuidv4 } = require('uuid');

const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

require("dotenv").config({ path: require("path").resolve(__dirname, "../keys.env")})

module.exports = function(pool){
    async function setOnline(username){
        try{
            await pool.query("UPDATE account SET isonline = $1 WHERE username = $2", [true, username]);
        }
        catch(err){
            console.log(err)
        }
    }
    
    route.post("/validateAccount", async (req, res)=>{
        try{
            const query = await pool.query("SELECT * FROM account WHERE username = $1", [sanitize(req.body.username)])
    
            let status = "Not Found";
            let username = "Not found";
            let login_token = "Not found";
            let player_account_type = "Not found";
            let isOnline = false
    
            if(query.rows.length > 0){
                let findAcc = query.rows[0];

                let passwordCorrect = await bcrypt.compare(sanitize(req.body.password), findAcc.password_hash)
    
                if(passwordCorrect){
                    status = "Account found"
                    username = findAcc.username;
                    login_token = findAcc.login_token;
                    player_account_type = findAcc.account_type;
                    isOnline = findAcc.isonline
    
                    if(!isOnline){
                        await setOnline(username)
                    }
                }
            }
            res.status(200).json({ status: status, username: username, login_token: login_token, player_type: player_account_type, isOnline: isOnline });
        }
        catch(err){
            console.log(err);
        }
    });
    
    async function delete_image(profile_hash){
        try{
            if(profile_hash != "ajVzRmV"){
                const deleteImg = await fetch(`https://api.imgur.com/3/image/${profile_hash}`, {
                    method: "DELETE",
                    headers: {
                        Authorization: `Bearer ${process.env.IMGUR_ACCESS_TOKEN}`
                    }
                });
    
                const deleteImg_res = await deleteImg.json();
    
                if(!deleteImg_res.success){
                    console.log(deleteImg_res)
                }
            }
        }
        catch(err){
            console.log(err);
        }
    }
    
    function hash_pass(pass){
        const salt = bcrypt.genSaltSync(10);
        const hash = bcrypt.hashSync(pass, salt);
        return hash;
    }
    
    let inGameName = [
        "bob123",
        "hotdogMighty_04",
        "ShadowNoodle",
        "CaptainCrush",
        "PixelPirate",
        "LaserBeard",
        "SneakyPenguin",
        "FunkyFalcon",
        "TacoKnight",
        "ZebraZap",
        "ToastViking",
        "ChocoSlayer",
        "NovaNugget",
        "TurboWaffle",
        "LlamaBlitz",
        "IceCreamSniper",
        "BananaBomber",
        "RoboDuck42",
        "WizardOfLOL",
        "MysticMeatball"
    ];
    
    route.post("/connectAccount", async (req, res)=>{
        try{
            const query = await pool.query("UPDATE account SET password_hash = $1, account_type = 'Player' WHERE username = $2 RETURNING *", [hash_pass(req.body.pass), sanitize(req.body.username)])
    
            let status = "Not Found";
            let account_type = "Guest";
    
            if(query.rows.length > 0){
                status = "Success";
                account_type = query.rows[0].account_type;
            }
            res.status(200).json({ status: status, accountType: account_type });
        }
        catch(err){
            console.log(err);
        }
    });
    
    route.post("/createAccount", async (req, res) =>{
        try{
            const query = await pool.query("SELECT * FROM account WHERE username = $1", [sanitize(req.body.username)]);
            let status = ""
    
            if(query.rows.length > 0){
                status = "Username already taken!";
            }
            else{
                await pool.query("INSERT INTO account (username, password_hash, account_type, login_token, isonline) VALUES ($1, $2, $3, $4, $5)", [sanitize(req.body.username), hash_pass(sanitize(req.body.password)), "Player", uuidv4(), true])

                await pool.query("INSERT INTO player_infos (username, in_game_name, diamond, profile, description, profile_hash, account_type) VALUES ($1, $2, $3, $4, $5, $6, 'Player')", [sanitize(req.body.username), inGameName[Math.floor(Math.random() * inGameName.length)], 1000, "https://res.cloudinary.com/drksqyii9/image/upload/v1749372872/default_profile_vw2q2o.png", "No description yet", "default_profile_vw2q2o"])
            }
            res.status(200).json({ status: status })
        }
        catch(err){
            console.log(err);
            res.status(500).json({ status: "failed"})
        }
    });
    
    route.post("/createGuestAccount", async (req, res)=>{
        try{
            function generatePassword() {
                var length = 8,
                    charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
                    retVal = "";
                for (var i = 0, n = charset.length; i < length; ++i) {
                    retVal += charset.charAt(Math.floor(Math.random() * n));
                }
                return retVal;
            }

            const query = await pool.query("INSERT INTO account (username, password_hash, account_type, login_token, isonline) VALUES ($1, $2, $3, $4, $5) RETURNING *", [sanitize(req.body.username), hash_pass(generatePassword()), "Guest", uuidv4(), true])
            
            let status = "failed";
            let username = "Not Found";
            let login_token = "Not Found";
            let player_account_type = "Not Found";
    
            if(query.rows.length > 0){
                let createAcc = query.rows[0]
                
                status = "Success";
                username = createAcc.username;
                login_token = createAcc.login_token;
                player_account_type = createAcc.account_type;

                await pool.query("INSERT INTO player_infos (username, in_game_name, diamond, profile, description, profile_hash, account_type) VALUES ($1, $2, $3, $4, $5, $6, 'Guest')", [sanitize(req.body.username), inGameName[Math.floor(Math.random() * inGameName.length)], 1000, "https://res.cloudinary.com/drksqyii9/image/upload/v1749372872/default_profile_vw2q2o.png", "No description yet", "default_profile_vw2q2o"])
            }
            res.status(200).json({ status: status, username: username, login_token: login_token, player_type: player_account_type })
        }
        catch(err){
            console.log(err);
            res.status(500).json({ status: "failed"})
        }
    });
    
    let first_come_first_serve = []
    
    route.post("/auth_auto_login", async (req, res)=>{
        try{
            let login_token = req.body.login_token;
            let status = "Failed";
    
            let username = "Not found";
            let player_account_type = "Not Found";
            let UUID = "Not Found";
            let client_token_result = { client_result: "Failed" }
    
            let data_obj = req.body.client_token
            first_come_first_serve.push(data_obj)
    
            const filterUser = first_come_first_serve.filter(entry => entry.username === data_obj.username)
            let token_status = filterUser.length == 1 ? "Accepted" : "Rejected";
    
            client_token_result = { username: data_obj.username, token: data_obj.token, status: token_status }
    
            const tokenToRemove = data_obj.token;
            setTimeout(() => {
                const index = first_come_first_serve.findIndex(t => t.token === tokenToRemove);
                if (index >= 0) first_come_first_serve.splice(index, 1);
            }, 5000);

            const query = await pool.query("SELECT * FROM account WHERE username = $1 AND login_token = $2", [req.body.username, login_token])
    
            if(query.rows.length > 0){
                let findUser = query.rows[0]

                status = "Success";
                username = findUser.username;
                player_account_type = findUser.account_type;
                UUID = findUser.login_token;
    
                if(client_token_result.status == "Accepted"){
                    await setOnline(username)
                }
            }
            else{
                const query_acc = await pool.query("SELECT * FROM account WHERE username = $1", [req.body.username])
                const query_player_info = await pool.query("SELECT * FROM player_infos WHERE username = $1", [req.body.username])
                
                if(query_acc.rows.length > 0 && query_player_info.rows.length > 0){
                    let playerInfo = query_player_info.rows[0]
                    let data = query_acc.rows[0];

                    //await delete_image(playerInfo.profile_hash);
                    await pool.query('DELETE FROM account WHERE username = $1', [data.username]);
                    await pool.query('DELETE FROM player_infos WHERE username = $1', [data.username]);
                    status = "Modified account on guest side, deleting....";
                }
            }
    
            res.status(200).json({ status: status, username: username, player_type: player_account_type, UUID: UUID, client_token_result: client_token_result })
        }
        catch(err){
            console.log(err);
        }
    });

    return route;
};