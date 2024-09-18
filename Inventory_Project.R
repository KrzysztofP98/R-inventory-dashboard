# Load necessary libraries
library(dplyr)
library(ggplot2)
library(tidyr)
library(lubridate)
library(shiny)
library(openxlsx)

# Read the CSV data file into a data frame
df <- data.frame(data)
data <- read.csv("C:/Users/krzys/Desktop/R language/Project/dataInventoryManagementRestaurant.csv")

#Cleaning the data set 


#Find entries lacking in decimal points & insert them in a suitable position
add_decimal_point <- function(entry) {
  if (!grepl("\\.", entry)) {       
    num_digits <- nchar(entry)
    if (num_digits == 5) {
      entry <- sub("(\\d{2})(\\d*)", "\\1.\\2", entry)
    } else if (num_digits == 4) {
      entry <- sub("(\\d)(\\d*)", "\\1.\\2", entry)
    }
  }
  return(entry)
}

# Apply the function to relevant columns
df <- df %>%
  mutate(WIND = sapply(WIND, add_decimal_point))
df <- df %>%
  mutate(LUFTTEMPERATUR = sapply(LUFTTEMPERATUR, add_decimal_point))

# Remove the first column and rename remaining columns
df <- df[, -1]
colnames(df) <- c("DEMAND_DATE","SQUID", "FISH", "SHRIMPS", "CHICKEN", "MEATBALLS", "LAMB", "STEAK", "WIND", "CLOUD_COVER", "RAINFALL", "SUN", "AIR_TEMP", "ISHOLIDAY", "WEEKEND")


# Convert DEMAND_DATE to Date format and extract the weekday
df$DEMAND_DATE <- as.Date(df$DEMAND_DATE, format = "%m.%d.%Y")
df$weekday <- weekdays(df$DEMAND_DATE)
week_order <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")


# Reshape the data from wide to long format to facilitate analysis
long_data <- pivot_longer(df, cols = c(SQUID, FISH, SHRIMPS, CHICKEN, MEATBALLS, LAMB, STEAK), names_to = "FOOD_ITEM", values_to = "DEMAND")

# Save the reshaped data to an Excel file
write.xlsx(long_data,  "C:/Users/krzys/Desktop/R language/inventories.xlsx")


# Create categorical variables for different weather and time conditions
long_data$Holiday <- ifelse(long_data$WEEKEND == 0 & long_data$ISHOLIDAY == 0, "Working day",
                            ifelse(long_data$WEEKEND == 1 & long_data$ISHOLIDAY == 0, "Weekend",
                                   ifelse(long_data$WEEKEND == 0 | long_data$ISHOLIDAY == 1, "Holiday", "Unknown")))
long_data$AIR_TEMP <- as.numeric(long_data$AIR_TEMP)
long_data$Temp <- cut(long_data$AIR_TEMP, breaks = c(-Inf, 0, 10, 20, Inf), labels = c("below 0", "0-10", "10-20", "20+"), include.lowest = TRUE)

long_data$RAINFALL <- as.numeric(long_data$RAINFALL)
long_data$RAIN <- cut(long_data$RAINFALL, breaks = c(-Inf, 0.25, 2.5, 7.6, Inf), labels = c("dry or trace", "drizzle", "moderate rain", "heavy rain"), include.lowest = TRUE)       

long_data$WIND <- as.numeric(long_data$WIND)
long_data$WIND_STRENGTH <- cut(long_data$WIND, breaks = quantile(long_data$WIND, c(0, 0.25, 0.5, 0.75, 1)), labels = c("weak wind", "moderate weak wind", "moderate strong wind", "strong wind"), include.lowest = TRUE)

long_data$SUN <- as.numeric(long_data$SUN)
long_data$RADIATION <- cut(long_data$SUN, breaks = quantile(long_data$SUN, c(0, 0.25, 0.5, 0.75, 1)), labels = c("weak radiation", "moderate weak radiation", "moderate strong radiation", "strong radiation"), include.lowest = TRUE)              

long_data$CLOUD_COVER <- as.numeric(long_data$CLOUD_COVER)
long_data$COVER <- cut(long_data$CLOUD_COVER, breaks = quantile(long_data$CLOUD_COVER, c(0, 0.25, 0.5, 0.75, 1)), labels = c("clear sky", "light clouds", "moderately dense clouds", "heavy and thick cover"), include.lowest = TRUE)              


# Calculate the total demand for each food item
sum_total <- long_data %>%
  group_by(FOOD_ITEM) %>%
  summarize(SUM_TOTAL = sum(DEMAND))

# Calculate the percentage of total demand for each food item
sum_total$percentage <- sum_total$SUM_TOTAL / sum(sum_total$SUM_TOTAL) * 100
sum_total$FOOD_ITEM <- reorder(sum_total$FOOD_ITEM, -sum_total$percentage)
sum_total$legend_label <- paste(sum_total$FOOD_ITEM, " (", round(sum_total$percentage, 1), "%)")

# Extract year and month from DEMAND_DATE and convert year to a factor
long_data$month <- month(long_data$DEMAND_DATE, label=TRUE)
long_data$year <- year(long_data$DEMAND_DATE)
long_data$factor <- as.factor(long_data$year)

# Define User Interface for Shiny App
ui <- fluidPage(
  titlePanel("Stuttgart Restaurant Inventory Dashboard"),
  sidebarLayout(
    sidebarPanel(
      textOutput("panel"),
      conditionalPanel(
        condition = 'input.tabset == "Weather/Position in the Week analysis"',
        selectInput("plot_category", "Choose Weather/Position in the Week", choices = c("Position in Week", "Temperature", "Rain", "Wind", "Sun", "Clouds")),
        radioButtons("plot_type", "Choose A Way to Summarise Demand", choices = c("Sum" = "sum", "Average" = "average"), selected = "sum"),
      ), 
      conditionalPanel(
        condition = 'input.tabset == "Change over Time Analysis"',
        selectInput("food_category_time", "Choose Food Category", choices = c("All", unique(long_data$FOOD_ITEM)), selected = "All"),
        selectInput("plot_category1", "Choose Time Frame", choices = c("Year", "Month", "Week")),
      )
    ),
    mainPanel(
      tabsetPanel(
        id = "tabset",
        tabPanel("Total Demand", "two",
                 conditionalPanel(
                   condition = 'input.tabset == "Total Demand"',
                   plotOutput("total_plot")
                 )
        ),
        tabPanel("Weather/Position in the Week analysis", "one",
                   conditionalPanel(
                     condition = 'input.tabset == "Weather/Position in the Week analysis"',
                     plotOutput("demand_plot")
                 )
        ),
        tabPanel("Change over Time Analysis", "three",
                 conditionalPanel(
                   condition = 'input.tabset == "Change over Time Analysis"',
                   plotOutput("time_plot")
                 )
        )
      )
    )
  )
)


# Define server logic for the Shiny app
server <- function(input, output) {
  
  # Reactive expression for filtering data based on time frame and food category
  filtered_data <- reactive({
    selected_category_time <- input$food_category_time
    if (input$plot_category1 == "Year") {
      if (selected_category_time == "All") {
        return(long_data %>%
                 group_by(year, FOOD_ITEM) %>%
                 summarize(FOOD_YEAR_MEAN = mean(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 filter(FOOD_ITEM == selected_category_time) %>%
                 group_by(year) %>%
                 summarize(FOOD_YEAR_MEAN = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category1 == "Month"){
      if (selected_category_time == "All") {
        return(long_data %>%
                 group_by(month, FOOD_ITEM) %>%
                 summarize(FOOD_MONTH_MEAN = mean(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 filter(FOOD_ITEM == selected_category_time) %>%
                 group_by(month) %>%
                 summarize(FOOD_MONTH_MEAN = mean(DEMAND, na.rm = TRUE)))
      }
    } else {
      if (selected_category_time == "All") {
        return(long_data %>%
                 group_by(weekday, FOOD_ITEM) %>%
                 summarize(FOOD_DAY_MEAN = mean(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 filter(FOOD_ITEM == selected_category_time) %>%
                 group_by(weekday) %>%
                 summarize(FOOD_DAY_MEAN = mean(DEMAND, na.rm = TRUE)))
      } 
    }
  }
  )
  
  # Generate plot for weather/position in the week analysis
  weather_position_data <- reactive({
    if (input$plot_category == "Position in Week") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, Holiday) %>%
                 summarize(sum_Demand = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, Holiday) %>%
                 summarize(H_Demand = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category == "Temperature") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, Temp) %>%
                 summarize(Sum_Demand = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, Temp) %>%
                 summarize(Avg_Demand = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category == "Rain") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, RAIN) %>%
                 summarize(SUM_RAIN_DEMAND = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, RAIN) %>%
                 summarize(RAIN_DEMAND = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category == "Wind") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, WIND_STRENGTH) %>%
                 summarize(SUM_WIND_DEMAND = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, WIND_STRENGTH) %>%
                 summarize(WIND_DEMAND = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category == "Sun") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, RADIATION) %>%
                 summarize(SUM_SUN_DEMAND = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, RADIATION) %>%
                 summarize(SUN_DEMAND = mean(DEMAND, na.rm = TRUE)))
      }
    } else if (input$plot_category == "Clouds") {
      if (input$plot_type == "sum") {
        return(long_data %>%
                 group_by(FOOD_ITEM, COVER) %>%
                 summarize(SUM_CLOUD_DEMAND = sum(DEMAND, na.rm = TRUE)))
      } else {
        return(long_data %>%
                 group_by(FOOD_ITEM, COVER) %>%
                 summarize(CLOUD_DEMAND = mean(DEMAND, na.rm = TRUE)))
      }
    }
  })
  
  # Generate plot for total demand analysis
  output$demand_plot <- renderPlot({
    data <- weather_position_data()
    if (input$plot_category == "Position in Week") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, sum_Demand, fill=Holiday)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Position in the Week") +
          scale_fill_manual(values=c("Working day"="coral", "Weekend"="coral3", "Holiday"="coral4" )) +
          theme_minimal()
      } else {
        ggplot(data, aes(FOOD_ITEM, H_Demand, fill=Holiday)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Position in the Week") +
          scale_fill_manual(values=c("Working day"="coral", "Weekend"="coral3", "Holiday"="coral4" ))
      }
    } else if (input$plot_category == "Temperature") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, Sum_Demand, fill=Temp)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Temperature") +
          scale_fill_manual(values=c("below 0"="blue", "0-10"="cornflowerblue", "10-20"="burlywood2", "20+"="burlywood3" ))
      } else {
        ggplot(data, aes(FOOD_ITEM, Avg_Demand, fill=Temp)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Temperature") +
          scale_fill_manual(values=c("below 0"="blue", "0-10"="cornflowerblue", "10-20"="burlywood2", "20+"="burlywood3" ))
      }
    } else if (input$plot_category == "Rain") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, SUM_RAIN_DEMAND, fill=RAIN)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Rainfall") +
          scale_fill_manual(values=c("dry or trace"="deepskyblue", "drizzle"="cadetblue1", "moderate rain"="darkgrey", "heavy rain"="antiquewhite4"))
      } else {
        ggplot(data, aes(FOOD_ITEM, RAIN_DEMAND, fill=RAIN)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Rainfall") +
          scale_fill_manual(values=c("dry or trace"="deepskyblue", "drizzle"="cadetblue1", "moderate rain"="darkgrey", "heavy rain"="antiquewhite4"))
      }
    } else if (input$plot_category == "Wind") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, SUM_WIND_DEMAND, fill=WIND_STRENGTH)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Wind") +
          scale_fill_manual(values=c("weak wind"="darkslategray2", "moderate weak wind"="darkslategray3", "moderate strong wind"="darkslategray4", "strong wind"="darkslategrey"))
      } else {
        ggplot(data, aes(FOOD_ITEM, WIND_DEMAND, fill=WIND_STRENGTH)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Wind") +
          scale_fill_manual(values=c("weak wind"="darkslategray2", "moderate weak wind"="darkslategray3", "moderate strong wind"="darkslategray4", "strong wind"="darkslategrey"))
      }
    } else if (input$plot_category == "Sun") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, SUM_SUN_DEMAND, fill=RADIATION)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Radiation") +
          scale_fill_manual(values=c("weak radiation"="cornsilk4", "moderate weak radiation"="darksalmon", "moderate strong radiation"="darkgoldenrod", "strong radiation"="darkgoldenrod1"))
      } else {
        ggplot(data, aes(FOOD_ITEM, SUN_DEMAND, fill=RADIATION)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Radiation") +
          scale_fill_manual(values=c("weak radiation"="cornsilk4", "moderate weak radiation"="darksalmon", "moderate strong radiation"="darkgoldenrod", "strong radiation"="darkgoldenrod1"))
      }
    } else if (input$plot_category == "Clouds") {
      if (input$plot_type == "sum") {
        ggplot(data, aes(FOOD_ITEM, SUM_CLOUD_DEMAND, fill=COVER)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Summed Demand", fill="Cloud cover") +
          scale_fill_manual(values=c("clear sky"="deepskyblue", "light clouds"="cadetblue1", "moderately dense clouds"="darkgrey", "heavy and thick cover"="antiquewhite4"))
      } else {
        ggplot(data, aes(FOOD_ITEM, CLOUD_DEMAND, fill=COVER)) +
          geom_bar(position="dodge", stat="identity") +
          labs(x="Food Item", y="Average Daily Demand", fill="Cloud cover") +
          scale_fill_manual(values=c("clear sky"="deepskyblue", "light clouds"="cadetblue1", "moderately dense clouds"="darkgrey", "heavy and thick cover"="antiquewhite4"))
      }
    } 
  }
  )
  
  # Generate plot for change over time analysis
  output$total_plot <- renderPlot({
    ggplot(sum_total, aes(x = "", y = percentage, fill = FOOD_ITEM)) +
      geom_bar(stat = "identity", width = 1, colour="white") +
      geom_text(aes(label = paste0(FOOD_ITEM, "\n", round(percentage, 1), "%"), x=1.6), position = position_stack(vjust = 0.5)) +
      coord_polar("y") +
      ggtitle("Total Demand") +
      labs(y = "Average Demand", fill="Food item") +
      scale_fill_manual(values=c("CHICKEN"="chartreuse4", "FISH"="purple", "LAMB"="deepskyblue4", "MEATBALLS"="brown3", "SHRIMPS"="pink", "SQUID"="darkorchid4", "STEAK"="orange")) +
      theme_void()
  })
  output$time_plot <- renderPlot({
    filtered_data_value <- filtered_data()
    if (input$plot_category1 == "Year") {
      if (input$food_category_time == "All") {
        ggplot(filtered_data_value, aes(year, FOOD_YEAR_MEAN, color=FOOD_ITEM)) + geom_point() +
          geom_line(aes(group = FOOD_ITEM, color=FOOD_ITEM)) +
          labs(x = "Year", y = "Average Demand", color="Food item") +
          scale_color_manual(values=c("CHICKEN"="chartreuse4", "FISH"="purple", "LAMB"="deepskyblue4", "MEATBALLS"="red", "SHRIMPS"="pink", "SQUID"="darkorchid4", "STEAK"="orange"))+
          scale_x_continuous(breaks = 2013:2015)
      } else {
        ggplot(filtered_data_value, aes(x = year, y = FOOD_YEAR_MEAN)) +
          geom_point() +
          geom_line() +
          labs(x = "Year", y = "Average Demand") +
          ggtitle(paste("Demand Over Years for", input$food_category_time)) +
          scale_x_continuous(breaks = 2013:2015)
      }
    } else if (input$plot_category1 == "Month"){
      if (input$food_category_time == "All") {
        ggplot(filtered_data_value, aes(x = as.numeric(factor(month, levels = month.abb)), y = FOOD_MONTH_MEAN, group = FOOD_ITEM, color = FOOD_ITEM)) +
          geom_point() +
          geom_line() +
          labs(x = "Month", y = "Average Demand") +
          scale_color_manual(values=c("CHICKEN"="chartreuse4", "FISH"="purple", "LAMB"="deepskyblue4", "MEATBALLS"="red", "SHRIMPS"="pink", "SQUID"="darkorchid4", "STEAK"="orange")) +
          ggtitle(paste("Demand Over Months for", input$food_category_time)) +
          scale_x_continuous(breaks = 1:12, labels = month.abb)
      } else {
        ggplot(filtered_data_value, aes(x = as.numeric(factor(month, levels = month.abb)), y = FOOD_MONTH_MEAN)) +
          geom_point() +
          geom_line() +
          labs(x = "Month", y = "Average Demand") +
          ggtitle(paste("Demand Over Months for", input$food_category_time)) + 
          scale_x_continuous(breaks = 1:12, labels = month.abb)
      }
    } else {
      if (input$food_category_time == "All") {
        ggplot(filtered_data_value, aes(factor(weekday, levels=week_order), FOOD_DAY_MEAN, color=FOOD_ITEM)) + geom_point() +
          geom_line(aes(group = FOOD_ITEM, color=FOOD_ITEM)) +
          labs(x = "Weekday", y = "Average Demand", color="Food item") +
          scale_color_manual(values=c("CHICKEN"="chartreuse4", "FISH"="purple", "LAMB"="deepskyblue4", "MEATBALLS"="red", "SHRIMPS"="pink", "SQUID"="darkorchid4", "STEAK"="orange"))
      } else {
        ggplot(filtered_data_value, aes(x = factor(weekday, levels=week_order), y = FOOD_DAY_MEAN,  group=1)) +
          geom_point() +
          geom_line() +
          labs(x = "Weekday", y = "Average Demand") +
          ggtitle(paste("Demand Over Weekdays for", input$food_category_time))
      }
    }
  })
}



# Run the Shiny app
shinyApp(ui, server)
