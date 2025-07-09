//Server side
const express = require('express');
const app = express();
const { createServer } = require('http');
const expressServer = createServer(app);
const bodyParser = require('body-parser')
const cron = require('node-cron');

//other necessary things such as file path etc
const path = require('path');

//dotenv for the envs
require('dotenv').config({ path: path.resolve(__dirname, '../keys.env') });

//POSTGRE SQL set up
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.userDB,
  host: 'localhost',
  database: 'Raid_Pixel',
  password:  process.env.passDB,
  port: 5432,
});

pool.query('SELECT current_database()', (err, res) => {
    if (err) {
      console.error('Error fetching DB name', err.stack);
    } else {
      console.log('Connected to DB:', res.rows[0].current_database);
    }
  });

//parse json
app.use(bodyParser.json({limit: '50mb'}));
app.use(bodyParser.urlencoded({limit: '50mb', extended: true}));

//middle ware to serve static files
app.use(express.static(path.join(__dirname, '../Public')));

// Serve the root folder and html
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '../Public', 'index.html'));
});

//Routers
app.use("/accountRoute", require("./accountRoutes")(pool));
app.use("/playerInformation", require("./playerInformationRoute")(pool));

//listen to port
const PORT = process.env.PORT;
expressServer.listen(PORT, async ()=>{
    console.log('Listening to port ' + PORT);
    await check_guest_account(pool)
});

//check account per 12:00 midnight
cron.schedule('0 0 * * *', async () => {
  console.log("Running guest cleanup at midnight...");
  await check_guest_account(pool);
});

async function check_guest_account(pool){
  try{
    await pool.query("DELETE FROM account WHERE account_type = 'Guest' AND date_active::DATE < CURRENT_DATE;");
    await pool.query("DELETE FROM player_infos WHERE account_type = 'Guest' AND date_active::DATE < CURRENT_DATE;");
  }
  catch(err){console.log(err)}
}