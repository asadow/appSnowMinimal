library(shiny)
library(dplyr)
library(here)
library(bslib)
library(DT)
library(ggplot2)

shovel_long <- readRDS(here("shovel_WIP.rds"))

# Function to clean location names
clean_location <- function(x) {
  gsub("^- \\d+\\. (.+)\\.$", "\\1", x)
}

ui <- page_sidebar(
  title = "Snow Removal Survey Explorer",
  sidebar = sidebar(
    dateInput("date", 
              "Select Date",
              min = min(as.Date(shovel_long$`End Date`)),
              max = max(as.Date(shovel_long$`End Date`))),
    selectInput("location",
                "Select Location",
                choices = unique(clean_location(shovel_long$location))),
    hr(),
    helpText("Select a date and location to view survey results")
  ),
  
  layout_columns(
    card(
      card_header("Survey Details",
                  downloadButton("download_data", "Download Data", class = "float-end")),
      DT::dataTableOutput("summary_table")
    ),
    card(
      card_header("Actions Summary"),
      plotOutput("action_plot")
    )
  )
)

server <- function(input, output, session) {
  
  # Reactive expression to filter data
  filtered_data <- reactive({
    req(input$date, input$location)
    
    # Filter for selected date and location
    shovel_long %>%
      filter(
        as.Date(`End Date`) == input$date,
        location == input$location
      )
  })
  
  DT_data <- reactive({
    df <- filtered_data()
    
    # Select relevant columns and format for display
    df %>%
      select(
        Time = `Time shovel route was completed.`,
        Weather = `Weather conditions.`,
        `Completed By` = `Shovel route completed by (full name).`,
        Action = action,
        Status = value
      ) %>%
      mutate(
        Status = ifelse(is.na(Status), "No", "Yes")
      )
  })
  
  # Create summary table
  output$summary_table <- DT::renderDataTable({
    DT_data() %>%
      DT::datatable(
        options = list(pageLength = 5),
        rownames = FALSE
      )
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      paste0("snow-removal-data_", 
             input$date, 
             "_", 
             input$location |> 
               snakecase::to_snake_case() |> 
               stringr::str_replace_all("_", "-"), 
             ".csv")
    },
    content = function(file) {
      write.csv(DT_data(), file, row.names = FALSE)
    }
  )
  
  # Create action visualization
  output$action_plot <- renderPlot({
    df <- filtered_data()
    
    # Create summary of actions
    df_summary <- df %>%
      group_by(action) %>%
      summarize(count = sum(!is.na(value))) %>%
      filter(!is.na(action))
    
    # Create bar plot
    ggplot(df_summary, aes(x = action, y = count)) +
      geom_col(fill = "steelblue") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
      labs(
        x = "Action",
        y = "Count",
        title = paste("Actions Taken on", input$date)
      )
  })
}

shinyApp(ui, server)
