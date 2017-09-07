using COECRCOMLib;
using IniParser;
using IniParser.Model;
using masterecr.Properties;
using Npgsql;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace openccr
{
    public partial class frmMain : Form
    {
        private Timer timerProcessor, timerMonitor;
        private int processings = 0;
        NotifyIcon trayIcon;

        IniData data;
        
        public frmMain()
        {
            InitializeComponent();
        }

        private void frmMain_Load(object sender, EventArgs e)
        {
            var parser = new FileIniDataParser();
            this.data = parser.ReadFile("config.ini");
            timerProcessor = new Timer();
            timerMonitor = new Timer();
            timerProcessor.Tick += new EventHandler(timerProcessor_Tick);
            timerMonitor.Tick += new EventHandler(timerMonitor_Tick);
            timerMonitor.Interval = 500;
            timerProcessor.Interval = 2000;
            
            this.Visible = false;
            this.ShowInTaskbar = false;

            trayIcon = new NotifyIcon()
            {
                Icon = Resources.AppIcon,
                Text = "MasterCCR",
                ContextMenu = new ContextMenu(new MenuItem[] {
                    new MenuItem("Show", Show)
                }),
                Visible = true
            };

            int result = 0;
            result = EcrCom.Open("PORT = " + data["cash_register"]["comm_port"]);
            if (result != 0)
            {
                addActivity("error", "Connection to ECR failed!");
                EcrCom.Close();
            }
            else
            {
                EcrCom.Close();
                timerProcessor.Start();
            }
            timerMonitor.Start();

        }

        private void Show(object sender, EventArgs e)
        {
            this.Visible = true;
        }

        private void timerMonitor_Tick(object sender, EventArgs e)
        {
            if (processings == 1)
            {
                this.Visible = false;
            }

            if (!timerProcessor.Enabled)
            {
                this.addActivity("error", "Activity stopped!");
                this.btnExit.Visible = true;
                timerMonitor.Stop();
            }
        }

        private void timerProcessor_Tick(object sender, EventArgs e)
        {
            processings++;
            lblProcessings.Text = "Poll: " + processings.ToString();
            
            try
            {
                string connstring = String.Format("Server={0};Port={1};" +
                    "User Id={2};Password={3};Database={4};",
                    data["database"]["host"], data["database"]["port"], 
                    data["database"]["username"], data["database"]["password"], data["database"]["database"]);

                NpgsqlConnection conn = new NpgsqlConnection(connstring);
                conn.Open();
                
                // Get the next unprocessed order
                DataSet dsOrder = new DataSet();
                DataTable dtOrder = new DataTable();

                string sql = "SELECT * FROM pos_order " +
                    "WHERE ecr_process = 0 AND create_date > current_date AND " +
                    "(SELECT SUM(qty) FROM pos_order_line WHERE order_id = pos_order.\"id\") > 0 ";

                string fiscalJournalIds = data["cash_register"]["fiscal_journal_id"];
                if (fiscalJournalIds != null)
                {
                    sql += " AND EXISTS (SELECT id FROM account_bank_statement_line WHERE pos_statement_id = pos_order.id " +
                        " AND journal_id IN (" + fiscalJournalIds + "))";
                }

                sql += " LIMIT 1";

                NpgsqlDataAdapter daOrder = new NpgsqlDataAdapter(sql, conn);
                dsOrder.Reset();
                daOrder.Fill(dsOrder);
                dtOrder = dsOrder.Tables[0];

                if (dtOrder.Rows.Count > 0)
                {
                    this.addActivity("info", "Order found. Processing...");
                    
                    DataRow rowOrder = dtOrder.Rows[0];

                    int result = 0;
                    result = EcrCom.Open("PORT = " + data["cash_register"]["comm_port"]);

                    if (result == 0)
                    {
                        string commandResult = "OK.";
                        this.addActivity("success", "ECR Communication opened. Sending data...");

                        EcrCom.EcrCmd("CLEAR", ref commandResult);
                        if (commandResult != "OK.") throw new InvalidOperationException(commandResult);

                        EcrCom.EcrCmd("CHIAVE REG", ref commandResult);
                        if (commandResult != "OK.") throw new InvalidOperationException(commandResult);

                        sql = "SELECT pos_order_line.\"id\", pos_order_line.product_id, " +
                            "qty, price_unit, product_template.name as product_name " +
                            "FROM pos_order_line " +
                            "JOIN product_product ON pos_order_line.product_id = product_product.id " +
                            "JOIN product_template ON product_template.id = product_product.product_tmpl_id " +
                            "WHERE pos_order_line.order_id = " + rowOrder["id"];

                        NpgsqlDataAdapter daOrderLine = new NpgsqlDataAdapter(sql, conn);
                        DataSet dsOrderLine = new DataSet();
                        dsOrderLine.Reset();
                        daOrderLine.Fill(dsOrderLine);
                        DataTable dtOrderLine = dsOrderLine.Tables[0];

                        foreach (DataRow rowOrderLine in dtOrderLine.Rows)
                        {
                            sql = "SELECT * FROM product_taxes_rel WHERE prod_id = " + rowOrderLine["product_id"];
                            NpgsqlDataAdapter daProductTaxes = new NpgsqlDataAdapter(sql, conn);
                            DataSet dsProductTaxes = new DataSet();
                            dsProductTaxes.Reset();
                            daProductTaxes.Fill(dsProductTaxes);
                            DataTable dtProductTaxes = dsProductTaxes.Tables[0];

                            string department = "1", otherDepartment = "2";
                            if (data["cash_register"]["default_department"] != null)
                            {
                                department = data["cash_register"]["default_department"];
                                otherDepartment = department == "1" ? "2" : "1";
                            }

                            if (dtProductTaxes.Rows.Count > 0)
                            {
                                department = otherDepartment;
                            }

                            EcrCom.EcrCmd(String.Format("VEND REP={0},qty={1},PREZZO={2},DES='{3}'",
                                department, rowOrderLine["qty"], rowOrderLine["price_unit"], rowOrderLine["product_name"]), ref commandResult);
                            
                            if (commandResult != "OK.") throw new InvalidOperationException(commandResult);
                        }

                        if (data["footer"]["footer"].ToUpper().Equals("TRUE"))
                        {
                            EcrCom.EcrCmd("ALLEGA ON", ref commandResult);
                            EcrCom.EcrCmd("CHIUD=1", ref commandResult);
                            EcrCom.EcrCmd("ALLEG RIGA='" + data["footer"]["message"] + "'", ref commandResult);
                            EcrCom.EcrCmd("ALLEGA FINE", ref commandResult);
                        }
                        else
                        {
                            EcrCom.EcrCmd("CHIU TEND = 1", ref commandResult);
                        }
                        
                        if (commandResult != "OK.") throw new InvalidOperationException(commandResult);

                        EcrCom.Close();
                        this.addActivity("info", "ECR Communication closed.");
                    }
                    else
                    {
                        throw new InvalidOperationException("Connection to ECR failed!");
                    }


                    NpgsqlCommand command = conn.CreateCommand();
                    command.CommandText = "UPDATE pos_order SET ecr_process = 1 WHERE id = @id";
                    command.Parameters.AddWithValue("id", rowOrder["id"]);
                    command.ExecuteNonQuery();
                    this.addActivity("success", "Order processed.");
                } 
                
                conn.Close();
            }
            catch (Exception ex)
            {
                this.addActivity("error", ex.Message);
                EcrCom.Close();
                timerProcessor.Stop();
            }
        }

        private void addActivity(string type, string message)
        {
            lstActivity.Items.Add(DateTime.Now.ToString("dd/MM HH:mm:ss") + "| " + type.ToUpper() + ": " + message);
            lstActivity.TopIndex = lstActivity.Items.Count - 1;
        }


        private void frmMain_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (e.CloseReason == CloseReason.WindowsShutDown) return;
            if (!timerProcessor.Enabled) return;
            e.Cancel = true;
            this.Visible = false;
        }

        private void btnExit_Click(object sender, EventArgs e)
        {
            QuitApplication();
        }

        private void QuitApplication()
        {
            trayIcon.Visible = false;
            Application.Exit();
        }
    }
}
